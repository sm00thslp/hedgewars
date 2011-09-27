/*
 * Hedgewars, a free turn based strategy game
 * Copyright (c) 2006-2011 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#include <QGridLayout>
#include <QVBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QListWidgetItem>
#include <QPushButton>

#include "pagetraining.h"
#include "hwconsts.h"

QLayout * PageTraining::bodyLayoutDefinition()
{
    QGridLayout * pageLayout = new QGridLayout();

// left column

    // declare start button, caption and description
    btnPreview = formattedButton(":/res/Trainings.png", true);
    btnPreview->setToolTip(QPushButton::tr("Go!"));

    // make both rows equal height
    pageLayout->setRowStretch(0, 1);
    pageLayout->setRowStretch(1, 1);

    // add start button, caption and description to 3 different rows
    pageLayout->addWidget(btnPreview, 0, 0);

    // center preview
    pageLayout->setAlignment(btnPreview, Qt::AlignRight | Qt::AlignVCenter);


// right column

    // info area (caption on top, description below)
    QVBoxLayout * infoLayout = new QVBoxLayout();

    lblCaption = new QLabel();
    lblCaption->setMinimumWidth(360);
    lblCaption->setAlignment(Qt::AlignHCenter | Qt::AlignBottom);
    lblCaption->setWordWrap(true);
    lblDescription = new QLabel();
    lblDescription->setMinimumWidth(360);
    lblDescription->setAlignment(Qt::AlignHCenter | Qt::AlignTop);
    lblDescription->setWordWrap(true);

    infoLayout->addWidget(lblCaption);
    infoLayout->addWidget(lblDescription);

    pageLayout->addLayout(infoLayout, 0, 1);
    pageLayout->setAlignment(infoLayout, Qt::AlignLeft);


    // mission list
    lstMissions = new QListWidget(this);
    pageLayout->addWidget(lstMissions, 1, 0, 1, 2); // span 2 columns

    // let's not make the list use more space than needed
    lstMissions->setFixedWidth(360);
    pageLayout->setAlignment(lstMissions, Qt::AlignHCenter);

    return pageLayout;
}

QLayout * PageTraining::footerLayoutDefinition()
{
    QBoxLayout * bottomLayout = new QVBoxLayout();

    btnStart = formattedButton(QPushButton::tr("Go!"));
    btnStart->setFixedWidth(140);

    bottomLayout->addWidget(btnStart);

    bottomLayout->setAlignment(btnStart, Qt::AlignRight | Qt::AlignVCenter);

    return bottomLayout;
}


void PageTraining::connectSignals()
{
    connect(lstMissions, SIGNAL(currentItemChanged(QListWidgetItem*, QListWidgetItem*)), this, SLOT(updateInfo()));
    connect(lstMissions, SIGNAL(clicked()), this, SLOT(updateInfo()));
    connect(lstMissions, SIGNAL(itemDoubleClicked(QListWidgetItem*)), this, SLOT(startSelected()));
    connect(btnPreview, SIGNAL(clicked()), this, SLOT(startSelected()));
    connect(btnStart, SIGNAL(clicked()), this, SLOT(startSelected()));
}


PageTraining::PageTraining(QWidget* parent) : AbstractPage(parent)
{
    initPage();

//  TODO -> this should be done in a tool "DataDir" class
    QDir tmpdir;
    tmpdir.cd(cfgdir->absolutePath());
    tmpdir.cd("Data/Missions/Training");
    QStringList missionList = scriptList(tmpdir);
    missionList.sort();

    tmpdir.cd(datadir->absolutePath());
    tmpdir.cd("Missions/Training");
    QStringList defaultList = scriptList(tmpdir);
    defaultList.sort();

    // add non-duplicate default scripts to the list
    foreach (const QString & mission, defaultList)
    {
        if (!missionList.contains(mission))
            missionList.append(mission);
    }

    // add only default scripts that have names different from detected user scripts
    foreach (const QString & mission, missionList)
    {
        QListWidgetItem * item = new QListWidgetItem(mission);

        // replace underscores in mission name with spaces
        item->setText(item->text().replace("_", " "));

        // store original name in data
        item->setData(Qt::UserRole, mission);

        lstMissions->addItem(item);
    }

    updateInfo();

    // pre-select first mission
    if (lstMissions->count() > 0)
        lstMissions->setCurrentRow(0);
}

QStringList PageTraining::scriptList(const QDir & scriptDir) const
{
    QDir dir = scriptDir;
    dir.setFilter(QDir::Files);
    return dir.entryList(QStringList("*.lua")).replaceInStrings(QRegExp("^(.*)\\.lua"), "\\1");
}


void PageTraining::startSelected()
{
    QListWidgetItem * curItem = lstMissions->currentItem();

    if (curItem != NULL)
        emit startMission(curItem->data(Qt::UserRole).toString());
}


void PageTraining::updateInfo()
{
    if (lstMissions->currentItem())
    {
        // TODO also use .pngs in userdata folder
        QString thumbFile = datadir->absolutePath() + "/Graphics/Missions/Training/" + lstMissions->currentItem()->data(Qt::UserRole).toString() + ".png";
        if (QFile::exists(thumbFile))
            btnPreview->setIcon(QIcon(thumbFile));
        else
            btnPreview->setIcon(QIcon(":/res/Trainings.png"));

        lblCaption->setText("<h2>" + lstMissions->currentItem()->text()+"</h2>");
        // TODO load mission description from file
        lblDescription->setText("< Imagine Mission Description here >\n\nThank you.");
    }
    else
    {
        btnPreview->setIcon(QIcon(":/res/Trainings.png"));
        lblCaption->setText(tr("Select a mission!"));
        // TODO better text and tr()
        lblDescription->setText("");
    }
}
