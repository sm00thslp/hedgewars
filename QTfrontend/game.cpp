/*
 * Hedgewars, a worms-like game
 * Copyright (c) 2005 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * Distributed under the terms of the BSD-modified licence:
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * with the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <QMessageBox>
#include <QProcess>
#include <QTimer>
#include <QString>
#include <QByteArray>
#include <QFile>
#include <QTextStream>

#include "game.h"
#include "hwconsts.h"
#include "gameuiconfig.h"
#include "gamecfgwidget.h"

HWGame::HWGame(GameUIConfig * config, GameCFGWidget * gamecfg)
{
	this->config = config;
	this->gamecfg = gamecfg;
	TeamCount = 0;
	seed = "";
}

void HWGame::NewConnection()
{
	QTcpSocket * client = IPCServer->nextPendingConnection();
	if(!IPCSocket)
	{
		IPCServer->close();
		IPCSocket = client;
		connect(client, SIGNAL(disconnected()), this, SLOT(ClientDisconnect()));
		connect(client, SIGNAL(readyRead()), this, SLOT(ClientRead()));
		if (toSendBuf.size() > 0)
			SENDIPC("?");
	} else
	{
		qWarning("2nd IPC client?!");
		client->disconnectFromHost();
	}
}

void HWGame::ClientDisconnect()
{
	SaveDemo("demo.hwd_1");
    IPCSocket->deleteLater();
	IPCSocket = 0;
	deleteLater();
}

void HWGame::SendTeamConfig(int index)
{
	LocalCFG(teams[index]);
}

void HWGame::SendConfig()
{
	SendIPC(QString("eseed %1").arg(seed));
	SendIPC(QString("etheme %1").arg(GetThemeBySeed()));
	SENDIPC("TL");
	SendIPC(QString("e$gmflags %1").arg(gamecfg->getGameFlags()));
	SENDIPC("eaddteam");
	LocalCFG(0);
	SENDIPC("ecolor 65535");
	SENDIPC("eadd hh0 0");
	SENDIPC("eadd hh1 0");
	SENDIPC("eadd hh2 0");
	SENDIPC("eadd hh3 0");
	SENDIPC("eaddteam");
	LocalCFG(2);
	SENDIPC("ecolor 16776960");
	SENDIPC("eadd hh0 1");
	SENDIPC("eadd hh1 1");
	SENDIPC("eadd hh2 1");
	SENDIPC("eadd hh3 1");
}

void HWGame::ParseMessage(const QByteArray & msg)
{
	switch(msg.data()[1])
	{
		case '?':
		{
			if (gameType == gtNet)
				emit SendNet(QByteArray("\x01""?"));
			else
				SENDIPC("!");
			break;
		}
		case 'C':
		{
			if (gameType == gtNet)
			{
				SENDIPC("TN");
				emit SendNet(QByteArray("\x01""C"));
			}
			else
			{
				if (gameType == gtLocal)
				 	SendConfig();
			}
			break;
		}
		case 'E':
		{
			QMessageBox::critical(0,
					"Hedgewars: error message",
					QString().append(msg.mid(2)).left(msg.size() - 6),
					QMessageBox::Ok,
					QMessageBox::NoButton,
					QMessageBox::NoButton);
			return;
		}
		case '+':
		{
			if (gameType == gtNet)
			{
				emit SendNet(msg);
			}
			break;
		}
		default:
		{
			if (gameType == gtNet)
			{
				emit SendNet(msg);
			}
			demo->append(msg);
		}
	}
}

void HWGame::SendIPC(const char * msg, quint8 len)
{
	SendIPC(QByteArray::fromRawData(msg, len));
}

void HWGame::SendIPC(const QString & buf)
{
	SendIPC(QByteArray().append(buf));
}

void HWGame::SendIPC(const QByteArray & buf)
{
	if (buf.size() > MAXMSGCHARS) return;
	quint8 len = buf.size();
	RawSendIPC(QByteArray::fromRawData((char *)&len, 1) + buf);
}

void HWGame::RawSendIPC(const QByteArray & buf)
{
	if (!IPCSocket)
	{
		toSendBuf += buf;
	} else
	{
		if (toSendBuf.size() > 0)
		{
			IPCSocket->write(toSendBuf);
			demo->append(toSendBuf);
			toSendBuf.clear();
		}
		IPCSocket->write(buf);
		demo->append(buf);
	}
}

void HWGame::FromNet(const QByteArray & msg)
{
	RawSendIPC(msg);
}

void HWGame::ClientRead()
{
	readbuffer.append(IPCSocket->readAll());
	quint8 msglen;
	quint32 bufsize;
	while (((bufsize = readbuffer.size()) > 0) &&
			((msglen = readbuffer.data()[0]) < bufsize))
	{
		QByteArray msg = readbuffer.left(msglen + 1);
		readbuffer.remove(0, msglen + 1);
		ParseMessage(msg);
	}
}

void HWGame::Start()
{
	IPCServer = new QTcpServer(this);
	connect(IPCServer, SIGNAL(newConnection()), this, SLOT(NewConnection()));
	IPCServer->setMaxPendingConnections(1);
	IPCSocket = 0;
	if (!IPCServer->listen(QHostAddress::LocalHost, IPC_PORT))
	{
		QMessageBox::critical(0, tr("Error"),
				tr("Unable to start the server: %1.")
				.arg(IPCServer->errorString()));
	}

	demo = new QByteArray;
	QProcess * process;
	QStringList arguments;
	process = new QProcess;
	arguments << resolutions[0][config->vid_Resolution()];
	arguments << resolutions[1][config->vid_Resolution()];
	arguments << "16";
	arguments << "46631";
	arguments << (config->vid_Fullscreen() ? "1" : "0");
	arguments << (config->isSoundEnabled() ? "1" : "0");
	arguments << tr("en.txt");
	process->start(bindir->absolutePath() + "/hwengine", arguments);
}

void HWGame::AddTeam(const QString & teamname)
{
	if (TeamCount == 5) return;
	teams[TeamCount] = teamname;
	TeamCount++;
}

QString HWGame::GetThemeBySeed()
{
	QFile themesfile(datadir->absolutePath() + "/Themes/themes.cfg");
	QStringList themes;
	if (themesfile.open(QIODevice::ReadOnly))
	{
		QTextStream stream(&themesfile);
		QString str;
		while (!stream.atEnd())
		{
			themes << stream.readLine();
		}
		themesfile.close();
	}
	quint32 len = themes.size();
	if (len == 0)
	{
		QMessageBox::critical(0, "Error", "Cannot access themes.cfg or bad data", "OK");
		return "avematan";
	}
	if (seed.isEmpty())
	{
		QMessageBox::critical(0, "Error", "seed not defined", "OK");
		return "avematan";
	}
	quint32 k = 0;
	for (int i = 0; i < seed.length(); i++)
	{
		k += seed[i].cell();
	}
	return themes[k % len];
}

void HWGame::SaveDemo(const QString & filename)
{
	QFile demofile(filename);
	if (!demofile.open(QIODevice::WriteOnly))
	{
		QMessageBox::critical(0,
				tr("Error"),
				tr("Cannot save demo to file %1").arg(filename),
				tr("Quit"));
		return ;
	}
	QDataStream stream(&demofile);
	stream.writeRawData(demo->constData(), demo->size());
	demofile.close();
	delete demo;
}

void HWGame::PlayDemo(const QString & demofilename)
{
	gameType = gtDemo;
	QFile demofile(demofilename);
	if (!demofile.open(QIODevice::ReadOnly))
	{
		QMessageBox::critical(0,
				tr("Error"),
				tr("Cannot open demofile %1").arg(demofilename),
				tr("Quit"));
		return ;
	}

	// read demo
	QDataStream stream(&demofile);
	char buf[512];
	quint32 readbytes;
	do
	{
		readbytes = stream.readRawData((char *)&buf, 512);
		toSendBuf.append(QByteArray((char *)&buf, readbytes));

	} while (readbytes > 0);
	demofile.close();

	// run engine
	Start();
}

void HWGame::StartNet()
{
	gameType = gtNet;
	demo = new QByteArray;
	Start();
}

void HWGame::StartLocal()
{
	gameType = gtLocal;
	if (TeamCount < 2) return;
	seedgen.GenRNDStr(seed, 10);
	Start();
}

void HWGame::StartQuick()
{
	gameType = gtLocal;
	seedgen.GenRNDStr(seed, 10);
	Start();
}


void HWGame::LocalCFG(const QString & teamname)
{
	HWTeam team(teamname, config);
	if (!team.LoadFromFile()) {
		QMessageBox::critical(0,
				"Error",
				QString("Cannot load team config ""%1""").arg(teamname),
				QMessageBox::Ok,
				QMessageBox::NoButton,
				QMessageBox::NoButton);
		return;
	}
	RawSendIPC(team.IPCTeamInfo());
}

void HWGame::LocalCFG(quint8 num)
{
	HWTeam team(num, config);
	RawSendIPC(team.IPCTeamInfo());
}
